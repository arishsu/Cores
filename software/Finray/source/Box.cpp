#include "stdafx.h"

namespace Finray {

ABox::ABox(Vector pt1, Vector d) : AnObject()
{
	int nn;
	ATriangle *o;
	Vector pt2, pt3, pt4, pt5, pt6, pt7, pt8;

	type = OBJ_BOX;

	maxLength = abs(d.x) > abs(d.y) ? abs(d.x) : abs(d.y);
	maxLength = maxLength > abs(d.z) ? maxLength : abs(d.z);

	for (nn = 0; nn < 12; nn++) {
		o = new ATriangle();
		tri[nn] = o;
		o->next = obj;
		obj = o;
	}

	pt2 = Vector::Add(pt1,Vector(d.x,0,0));
	pt3 = Vector::Add(pt1,Vector(d.x,0,d.z));
	pt4 = Vector::Add(pt1,d);
	pt5 = Vector::Add(pt1,Vector(d.x,d.y,0));
	pt6 = Vector::Add(pt1,Vector(0,d.y,0));
	pt7 = Vector::Add(pt1,Vector(0,d.y,d.z));
	pt8 = Vector::Add(pt1,Vector(0,0,d.z));

	// right
	tri[0]->p1 = pt2;
	tri[0]->p2 = pt3;
	tri[0]->p3 = pt4;
	tri[1]->p1 = pt4;
	tri[1]->p2 = pt5;
	tri[1]->p3 = pt2;
	// front
	tri[2]->p1 = pt1;
	tri[2]->p2 = pt2;
	tri[2]->p3 = pt5;
	tri[3]->p1 = pt5;
	tri[3]->p2 = pt6;
	tri[3]->p3 = pt1;
	//left
	tri[4]->p1 = pt1;
	tri[4]->p2 = pt8;
	tri[4]->p3 = pt7;
	tri[5]->p1 = pt7;
	tri[5]->p2 = pt6;
	tri[5]->p3 = pt1;
	// back face
	tri[6]->p1 = pt8;
	tri[6]->p2 = pt3;
	tri[6]->p3 = pt4;
	tri[7]->p1 = pt4;
	tri[7]->p2 = pt7;
	tri[7]->p3 = pt8;
	// bottom
	tri[8]->p1 = pt1;
	tri[8]->p2 = pt2;
	tri[8]->p3 = pt3;
	tri[9]->p1 = pt3;
	tri[9]->p2 = pt8;
	tri[9]->p3 = pt1;
	// top
	tri[10]->p1 = pt6;
	tri[10]->p2 = pt5;
	tri[10]->p3 = pt4;
	tri[11]->p1 = pt4;
	tri[11]->p2 = pt7;
	tri[11]->p3 = pt6;

	o = (ATriangle *)obj;
	while (o) {
		o->Init();
		o->CalcBoundingObject();
		o = (ATriangle *)o->next;
	}
	CalcBoundingObject();
}

ABox::ABox() : AnObject()
{
	int nn;
	Vector pt1,pt2,pt3,pt4,pt5,pt6,pt7,pt8;
	ATriangle *o;

	type = OBJ_BOX;

	maxLength = 1.0;

	for (nn = 0; nn < 12; nn++) {
		o = new ATriangle();
		tri[nn] = o;
		o->next = obj;
		obj = o;
	}

	pt1 = Vector(1,0,0);
	pt2 = Vector(1,0,1);
	pt3 = Vector(1,1,1);
	pt4 = Vector(1,1,0);
	pt5 = Vector(0,0,0);
	pt6 = Vector(0,0,1);
	pt7 = Vector(0,1,1);
	pt8 = Vector(0,1,0);

	// right
	tri[0]->p1 = pt1;
	tri[0]->p2 = pt2;
	tri[0]->p3 = pt3;
	tri[1]->p1 = pt1;
	tri[1]->p2 = pt3;
	tri[1]->p3 = pt4;
	// front
	tri[2]->p1 = pt1;
	tri[2]->p2 = pt4;
	tri[2]->p3 = pt5;
	tri[3]->p1 = pt5;
	tri[3]->p2 = pt4;
	tri[3]->p3 = pt8;
	//left
	tri[4]->p1 = pt5;
	tri[4]->p2 = pt6;
	tri[4]->p3 = pt7;
	tri[5]->p1 = pt7;
	tri[5]->p2 = pt8;
	tri[5]->p3 = pt5;
	// back face
	tri[6]->p1 = pt2;
	tri[6]->p2 = pt6;
	tri[6]->p3 = pt3;
	tri[7]->p1 = pt3;
	tri[7]->p2 = pt6;
	tri[7]->p3 = pt7;
	// bottom
	tri[8]->p1 = pt5;
	tri[8]->p2 = pt1;
	tri[8]->p3 = pt2;
	tri[9]->p1 = pt5;
	tri[9]->p2 = pt2;
	tri[9]->p3 = pt6;
	// top
	tri[10]->p1 = pt8;
	tri[10]->p2 = pt4;
	tri[10]->p3 = pt3;
	tri[11]->p1 = pt3;
	tri[11]->p2 = pt7;
	tri[11]->p3 = pt8;

	o = (ATriangle *)obj;
	while (o) {
		o->Init();
		o->CalcBoundingObject();
		o = (ATriangle *)o->next;
	}
	CalcBoundingObject();
}

ABox::ABox(double x, double y, double z) : AnObject()
{
	int nn;
	Vector pt1,pt2,pt3,pt4,pt5,pt6,pt7,pt8;
	ATriangle *o;

	type = OBJ_BOX;
	obj = nullptr;
	next = nullptr;
	negobj = nullptr;

	maxLength = abs(x) > abs(y) ? abs(x) : abs(y);
	maxLength = maxLength > abs(z) ? maxLength : abs(z);

	for (nn = 0; nn < 12; nn++) {
		o = new ATriangle();
		tri[nn] = o;
		o->next = obj;
		obj = o;
	}

	pt1 = Vector(x,0,0);
	pt2 = Vector(x,0,z);
	pt3 = Vector(x,y,z);
	pt4 = Vector(x,y,0);
	pt5 = Vector(0,0,0);
	pt6 = Vector(0,0,z);
	pt7 = Vector(0,y,z);
	pt8 = Vector(0,y,0);

	// right
	tri[0]->p1 = pt1;
	tri[0]->p2 = pt2;
	tri[0]->p3 = pt3;
	tri[1]->p1 = pt1;
	tri[1]->p2 = pt3;
	tri[1]->p3 = pt4;
	// front
	tri[2]->p1 = pt1;
	tri[2]->p2 = pt4;
	tri[2]->p3 = pt5;
	tri[3]->p1 = pt5;
	tri[3]->p2 = pt4;
	tri[3]->p3 = pt8;
	//left
	tri[4]->p1 = pt5;
	tri[4]->p2 = pt6;
	tri[4]->p3 = pt7;
	tri[5]->p1 = pt7;
	tri[5]->p2 = pt8;
	tri[5]->p3 = pt5;
	// back face
	tri[6]->p1 = pt2;
	tri[6]->p2 = pt6;
	tri[6]->p3 = pt3;
	tri[7]->p1 = pt3;
	tri[7]->p2 = pt6;
	tri[7]->p3 = pt7;
	// bottom
	tri[8]->p1 = pt5;
	tri[8]->p2 = pt1;
	tri[8]->p3 = pt2;
	tri[9]->p1 = pt5;
	tri[9]->p2 = pt2;
	tri[9]->p3 = pt6;
	// top
	tri[10]->p1 = pt8;
	tri[10]->p2 = pt4;
	tri[10]->p3 = pt3;
	tri[11]->p1 = pt3;
	tri[11]->p2 = pt7;
	tri[11]->p3 = pt8;

	o = (ATriangle *)obj;
	while (o) {
		o->Init();
		o->CalcBoundingObject();
		o = (ATriangle *)o->next;
	}
	CalcBoundingObject();
}

int ABox::Intersect(Ray *ray, double *t) { return 0; }
/*
{
	int nn;

	for (nn = 0; nn < 12; nn++) {
		if (triangles[nn].Intersect(ray, t) > 0) {
			intersectedTriangle = nn;
			return 1;
		}
	}
	return 0;
}
*/

Vector ABox::Normal(Vector v) {
	return Vector(1,0,0);
};
/*
{
	return triangles[intersectedTriangle].Normal(v);
}
*/
void ABox::RotX(double a)
{
	int nn;

	for (nn = 0; nn < 12; nn++) {
		tri[nn]->RotX(a);
	}
	if (boundingObject)
		boundingObject->RotX(a);
}

void ABox::RotY(double a)
{
	int nn;

	for (nn = 0; nn < 12; nn++) {
		tri[nn]->RotY(a);
	}
	if (boundingObject)
		boundingObject->RotY(a);
}

void ABox::RotZ(double a)
{
	int nn;

	for (nn = 0; nn < 12; nn++) {
		tri[nn]->RotZ(a);
	}
	if (boundingObject)
		boundingObject->RotZ(a);
}

void ABox::Translate(Vector p)
{
	int nn;

	for (nn = 0; nn < 12; nn++) {
		tri[nn]->Translate(p);
	}
	if (boundingObject)
		boundingObject->Translate(p);
}

void ABox::Translate(double x, double y, double z)
{
	Vector p = Vector(x,y,z);
	Translate(p);
	if (boundingObject)
		boundingObject->Translate(p);
}

void ABox::Scale(Vector p)
{
	int nn;

	for (nn = 0; nn < 12; nn++) {
		tri[nn]->Scale(p);
	}
	if (boundingObject)
		boundingObject->Scale(p);
}

void ABox::SetTexture(Surface *tx)
{
	int nn;

	for (nn = 0; nn < 12; nn++) {
		tri[nn]->SetTexture(tx);
	}
}

void ABox::SetColor(Color c)
{
	int nn;

	for (nn = 0; nn < 12; nn++) {
		tri[nn]->SetColor(c);
	}
}

void ABox::SetVariance(Color v)
{
	int nn;

	for (nn = 0; nn < 12; nn++) {
		tri[nn]->SetColorVariance(v);
	}
}

Vector ABox::CalcCenter()
{
	center = Vector(0,0,0);
	int nn;

	for (nn = 0; nn < 12; nn++) {
		center = Vector::Add(center,tri[nn]->p1);
		center = Vector::Add(center,tri[nn]->p2);
		center = Vector::Add(center,tri[nn]->p3);
	}
	center = Vector::Scale(center,1.0/36.0);
	return center;
}

double ABox::CalcRadius()
{
	int nn;
	double d1,d2,d3;
	radius = 0.0;

	for (nn = 0; nn < 12; nn++) {
		d1 = Vector::Length(Vector::Sub(center,tri[nn]->p1));
		d2 = Vector::Length(Vector::Sub(center,tri[nn]->p2));
		d3 = Vector::Length(Vector::Sub(center,tri[nn]->p3));
	}
	radius = abs(d1) > radius ? abs(d1) : radius;
	radius = abs(d2) > radius ? abs(d2) : radius;
	radius = abs(d3) > radius ? abs(d3) : radius;
	radius += EPSILON;
	radius2 = SQUARE(radius);
	return radius;
}

void ABox::CalcBoundingObject()
{
	CalcCenter();
	CalcRadius();
}

};
