// Much of this code originated from POV-Ray
//
#include "stdafx.h"

namespace Finray {

const double ACone::tolerance = 1e-09;

ACylinder::ACylinder(Vector b, Vector a, double r) : ACone(b, a, r, r)
{
	type = OBJ_CYLINDER;
/*
	base = b;
	apex = a;
	baseRadius = r;
	apexRadius = r;
	next = nullptr;
	obj = nullptr;
	negobj = nullptr;
*/
	CalcTransform();
}

void ACylinder::CalcTransform()
{
	double tmpf;
	Vector axis;

	axis = Vector::Sub(apex, base);
	tmpf = Vector::Length(axis);

	if (tmpf < EPSILON) {
		throw gcnew Finray::FinrayException(ERR_DEGENERATE,1);
	}
	else {
		axis = Vector::Scale(axis, 1.0/tmpf);
		trans.CalcCoordinate(base, axis, apexRadius, tmpf);
	}
	length = 0.0;
	CalcBoundingObject();
}


int ACylinder::Intersect(Ray *ray, double *t)
{
	int i = 0;
	double a, b, c, z, t1, t2, len;
	double d;
	Vector P, D;

	/* Transform the ray into the cones space */

	P = trans.InvTransPoint(ray->origin);
	D = trans.InvTransDirection(ray->dir);
	len = D.Length(D);
	D = Vector::Normalize(D);

	/* Solve intersections with a cylinder */

	a = D.x * D.x + D.y * D.y;

	if (a > EPSILON) {
		b = P.x * D.x + P.y * D.y;
		c = P.x * P.x + P.y * P.y - 1.0;
		d = b * b - a * c;

		if (d >= 0.0) {
			d = sqrt(d);
			t1 = (-b + d) / a;
			t2 = (-b - d) / a;
			z = P.z + t1 * D.z;
			if ((t1 > tolerance) && (t1 < BIG) && (z >= 0.0) && (z <= 1.0))
			{
				*t = t1 / len;
				intersectedPart = ACone::BODY;
				return 1;
			}

			z = P.z + t2 * D.z;
			if ((t2 > tolerance) && (t2 < BIG) && (z >= 0.0) && (z <= 1.0))
			{
				*t = t2 / len;
				intersectedPart = ACone::BODY;
				return 1;
			}
		}
	}

	if (openApex && (fabs(D.z) > EPSILON))
	{
		d = (1.0 - P.z) / D.z;
		a = (P.x + d * D.x);
		b = (P.y + d * D.y);

		if (((SQUARE(a) + SQUARE(b)) <= 1.0) && (d > tolerance) && (d < BIG))
		{
			*t = d / len;
			intersectedPart = APEX;
			return 1;
		}
	}
	if (openBase && (fabs(D.z) > EPSILON)) {
		d = (length - P.z) / D.z;
		a = (P.x + d * D.x);
		b = (P.y + d * D.y);

		if (((SQUARE(a) + SQUARE(b)) <= 1.0)
			&& (d > tolerance) && (d < BIG))
		{
			*t = d / len;
			intersectedPart = ACone::BASE;
			return 1;
		}
	}
	return 0;
}


ACone::ACone(Vector b, Vector a, double rb, double ra) : AnObject()
{
	type = OBJ_CONE;
	base = b;
	apex = a;
	baseRadius = rb;
	apexRadius = ra;
	CalcTransform();
}

void ACone::CalcCylinderTransform()
{
	double tmpf;
	Vector axis;

	axis = Vector::Sub(apex, base);
	tmpf = Vector::Length(axis);

	if (tmpf < EPSILON) {
		throw gcnew Finray::FinrayException(ERR_DEGENERATE,0);
	}
	else
	{
		axis = Vector::Scale(axis, 1.0/tmpf);
		trans.CalcCoordinate(base, axis, apexRadius, tmpf);
	}
	length = 0.0;
	CalcBoundingObject();
}


void ACone::CalcTransform()
{
	double tlen, len, tmpf;
	Vector tmpv, axis, origin;

	/* Process the primitive specific information */

	/* Find the axis and axis length */

	axis = Vector::Sub(apex, base);
	len = Vector::Length(axis);

	if (len < EPSILON) {
		throw gcnew Finray::FinrayException(ERR_DEGENERATE,0);
	}
	else {
		axis = Vector::Normalize(axis);
	}
	/* we need to trap that case first */
	if (fabs(apexRadius - baseRadius) < EPSILON)
	{
		/* What we are dealing with here is really a cylinder */
		type = OBJ_CYLINDER;
		CalcCylinderTransform();
		return;
	}

	// Want the bigger end at the top
	if (apexRadius < baseRadius)
	{
		tmpv = base;
		base = apex;
		apex = tmpv;
		tmpf = baseRadius;
		baseRadius = apexRadius;
		apexRadius = tmpf;
		axis = Vector::Scale(axis,-1.0);
	}
	/* apex & base are different, yet, it might looks like a cylinder */
	tmpf = baseRadius * len / (apexRadius - baseRadius);
	origin = Vector::Scale(axis, tmpf);
	origin = Vector::Sub(base, origin);

	tlen = tmpf + len;
	/* apex is always bigger here */
	if (((apexRadius - baseRadius)*len/tlen) < EPSILON)
	{
		/* What we are dealing with here is really a cylinder */
		type = OBJ_CYLINDER;
		CalcCylinderTransform();
		return;
	}

	length = tmpf / tlen;
	/* Determine alignment */
	trans.CalcCoordinate(origin, axis, apexRadius, tlen);
	CalcBoundingObject();
}

void ACone::RotXYZ(double ax, double ay, double az)
{
	Vector v;
	Transform T;
	v.x = ax;
	v.y = ay;
	v.z = az;
	T.CalcRotation(v);
	TransformX(&T);
	CalcTransform();
}

void ACone::Translate(double ax, double ay, double az)
{
	Vector v;
	Transform T;
	v.x = ax;
	v.y = ay;
	v.z = az;
	T.CalcTranslation(v);
	TransformX(&T);
	CalcTransform();
}

void ACone::Scale(Vector v)
{
	Transform T;
	T.CalcScaling(v);
	TransformX(&T);
	CalcTransform();
}

void ACone::Scale(double ax, double ay, double az)
{
	Vector v;
	Transform T;
	v.x = ax;
	v.y = ay;
	v.z = az;
	T.CalcScaling(v);
	TransformX(&T);
	CalcTransform();
}

Vector ACone::Normal(Vector p)
{
	Vector res = trans.InvTransPoint(p);

	if (intersectedPart==BASE) {
		res = Vector(0.0,0.0,-1.0);
	}
	else if (intersectedPart==APEX) {
		res = Vector(0.0,0.0,1.0);
	}
	else {
		if (type==OBJ_CYLINDER)
			res.z = 0.0;
		else
			res.z = -res.z;
	}
	return Vector::Normalize(trans.TransNormal(res));
}

int ACone::Intersect(Ray *ray, double *t)
{
	int i = 0;
	double a, b, c, z, t1, t2, len;
	double d;
	Vector P, D;

	/* Transform the ray into the cones space */

	P = trans.InvTransPoint(ray->origin);
	D = trans.InvTransDirection(ray->dir);

	len = D.Length(D);
	D = Vector::Normalize(D);

	/* Solve intersections with a cone */

	a = D.x * D.x + D.y * D.y - D.z * D.z;
	b = D.x * P.x + D.y * P.y - D.z * P.z;
	c = P.x * P.x + P.y * P.y - P.z * P.z;

	if (fabs(a) < EPSILON)
	{
		if (fabs(b) > EPSILON)
		{
			/* One intersection */
			t1 = -0.5 * c / b;
			z = P.z + t1 * D.z;
			if ((t1 > tolerance) && (t1 < BIG) && (z >= length) && (z <= 1.0))
			{
				*t = t1 / len;
				intersectedPart = BODY;
				return 1;
			}
		}
	}
	else
	{
		/* Check hits against the side of the cone */

		d = b * b - a * c;
		if (d >= 0.0)
		{
			d = sqrt(d);
			t1 = (-b - d) / a;
			t2 = (-b + d) / a;
			z = P.z + t1 * D.z;
			if ((t1 > tolerance) && (t1 < BIG) && (z >= length) && (z <= 1.0))
			{
				*t = t1 / len;
				intersectedPart = BODY;
				return 1;
			}

			z = P.z + t2 * D.z;
			if ((t2 > tolerance) && (t2 < BIG) && (z >= length) && (z <= 1.0))
			{
				*t = t2 / len;
				intersectedPart = BODY;
				return 1;
			}
		}
	}

	if (openApex && (fabs(D.z) > EPSILON))
	{
		d = (1.0 - P.z) / D.z;
		a = (P.x + d * D.x);
		b = (P.y + d * D.y);

		if (((SQUARE(a) + SQUARE(b)) <= 1.0) && (d > tolerance) && (d < BIG))
		{
			*t = d / len;
			intersectedPart = APEX;
			return 1;
		}
	}

	if (openBase && (fabs(D.z) > EPSILON))
	{
		d = (length - P.z) / D.z;
		a = (P.x + d * D.x);
		b = (P.y + d * D.y);

		if ((SQUARE(a) + SQUARE(b)) <= (SQUARE(length))
			&& (d > tolerance) && (d < BIG))
		{
			*t = d / len;
			intersectedPart = BASE;
			return 1;
		}
	}

	return 0;
}

void ACone::TransformX(Transform *t)
{
	trans.Compose(t);
}

void ACone::CalcCenter()
{
	center = Vector::Add(apex,base);
	center = Vector::Scale(center,0.5);
}

void ACone::CalcBoundingObject()
{
	double d1,d2, h;
	Vector axis;

	axis = Vector::Sub(apex, base);
	d1 = Vector::Length(axis) / 2.0; 
	d2 = baseRadius > apexRadius ? baseRadius : apexRadius;
	radius = sqrt((d1*d1) + (d2*d2)) + EPSILON;
	radius2 = SQUARE(radius);
}

};
